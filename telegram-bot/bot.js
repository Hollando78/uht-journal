import TelegramBot from 'node-telegram-bot-api';
import { execSync, exec } from 'node:child_process';

const TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const CHAT_ID = process.env.TELEGRAM_CHAT_ID;

if (!TOKEN) {
  console.error('TELEGRAM_BOT_TOKEN not set');
  process.exit(1);
}

const bot = new TelegramBot(TOKEN, { polling: true });

// --- Helpers ---

function run(cmd, timeout = 15000) {
  return execSync(cmd, { encoding: 'utf-8', timeout }).trim();
}

function reply(chatId, text) {
  bot.sendMessage(chatId, text);
}

function queryFact(predicate) {
  try {
    const out = run(`uht-substrate facts query --predicate ${predicate}`);
    const parsed = JSON.parse(out);
    return parsed.facts || [];
  } catch {
    return [];
  }
}

function getFactValue(predicate) {
  const facts = queryFact(predicate);
  return facts[0]?.object || null;
}

function isAuthorized(msg) {
  if (!CHAT_ID) return true;
  return String(msg.chat.id) === String(CHAT_ID);
}

// --- Commands ---

// /status
bot.onText(/\/status/, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    const session = getFactValue('SESSION_COUNT') || '0';
    const lastEnd = getFactValue('LAST_SESSION_END') || 'never';
    const lastTask = getFactValue('LAST_TASK_CLASS') || 'none';

    let nextRun = 'unknown';
    if (lastEnd && lastEnd !== 'never') {
      const next = new Date(new Date(lastEnd).getTime() + 60 * 60 * 1000);
      nextRun = `~${next.toISOString().replace('T', ' ').slice(0, 16)} UTC`;
    }

    reply(msg.chat.id,
      `UHT Loop Status\n` +
      `\n` +
      `Session: #${session}\n` +
      `Last task: ${lastTask}\n` +
      `Last completed: ${lastEnd}\n` +
      `Next scheduled: ${nextRun}`
    );
  } catch (err) {
    reply(msg.chat.id, `Status check failed: ${err.message}`);
  }
});

// /redirect <task_class>
bot.onText(/\/redirect\s+(\S+)/, (msg, match) => {
  if (!isAuthorized(msg)) return;

  const taskClass = match[1].toUpperCase();
  const valid = ['INTEGRITY', 'TRACE_GAP', 'CALIBRATION', 'CORPUS_EXPANSION', 'APPLICATION'];

  if (!valid.includes(taskClass)) {
    reply(msg.chat.id, `Invalid. Options: ${valid.join(', ')}`);
    return;
  }

  try {
    run(`uht-substrate facts upsert "autonomous-loop" PENDING_DIRECTIVE "TASK:${taskClass}" --namespace CLAUDE`);
    reply(msg.chat.id, `Next session will run: ${taskClass}`);
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /reqs
bot.onText(/\/reqs/, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    const out = run(`airgen reqs list uht-bot uht-research --json`, 30000);
    const parsed = JSON.parse(out);
    const reqs = parsed.data || parsed;

    if (!reqs.length) {
      reply(msg.chat.id, 'No requirements yet.');
      return;
    }

    const byDoc = {};
    for (const r of reqs) {
      const doc = r.document || 'unassigned';
      byDoc[doc] = (byDoc[doc] || 0) + 1;
    }

    let lines = [`AIRGen: uht-research (${reqs.length} reqs)\n`];
    for (const [doc, count] of Object.entries(byDoc)) {
      lines.push(`  ${doc}: ${count}`);
    }

    lines.push(`\nRecent:`);
    for (const r of reqs.slice(-3)) {
      const text = (r.text || '').slice(0, 55);
      lines.push(`  ${r.ref}: ${text}...`);
    }

    reply(msg.chat.id, lines.join('\n'));
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /expand <domain>
bot.onText(/\/expand\s+(.+)/, (msg, match) => {
  if (!isAuthorized(msg)) return;

  const domain = match[1].trim();
  try {
    run(`uht-substrate facts store "autonomous-loop" EXPANSION_TARGET "${domain}" --namespace CLAUDE`);
    reply(msg.chat.id, `Queued corpus expansion: ${domain}`);
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /experiment <description>
bot.onText(/\/experiment\s+(.+)/s, (msg, match) => {
  if (!isAuthorized(msg)) return;

  const description = match[1].trim();
  if (description.length < 10) {
    reply(msg.chat.id, 'Too short — describe the experiment in at least a sentence.');
    return;
  }

  try {
    run(`uht-substrate facts store "operator-directed" OPEN_HYPOTHESIS "${description.replace(/"/g, '\\"')}" --namespace CLAUDE`);
    run(`uht-substrate facts upsert "autonomous-loop" PENDING_DIRECTIVE "TASK:CALIBRATION" --namespace CLAUDE`);
    reply(msg.chat.id, `Experiment queued for next CALIBRATION session:\n\n${description}`);
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /pause
bot.onText(/\/pause/, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    run(`uht-substrate facts upsert "autonomous-loop" PENDING_DIRECTIVE "PAUSE" --namespace CLAUDE`);
    reply(msg.chat.id, 'Loop paused. Send /resume to restart.');
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /resume
bot.onText(/\/resume/, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    const facts = queryFact('PENDING_DIRECTIVE');
    const pauseFact = facts.find((f) => f.object === 'PAUSE');
    if (pauseFact) {
      run(`uht-substrate facts delete "${pauseFact.uuid}"`);
      reply(msg.chat.id, 'Loop resumed.');
    } else {
      reply(msg.chat.id, 'Loop is not paused.');
    }
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /run-now
bot.onText(/\/run-now/, (msg) => {
  if (!isAuthorized(msg)) return;

  exec('systemctl start uht-loop.service', (err) => {
    if (err) {
      reply(msg.chat.id, `Trigger failed: ${err.message}`);
    } else {
      reply(msg.chat.id, 'Session triggered. You will get a message when it completes.');
    }
  });
});

// ── QC Bot Commands ──

// /qc-status
bot.onText(/\/qc-status/, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    const session = getFactValue('QC_SESSION_COUNT') || '0';
    const lastEnd = getFactValue('QC_LAST_SESSION_END') || 'never';
    const lastTask = getFactValue('QC_LAST_TASK_CLASS') || 'none';

    let pendingActions = 0;
    try {
      const queueFacts = run(`uht-substrate facts query --predicate QC_ACTION_QUEUE --namespace QUALITY`, 15000);
      const parsed = JSON.parse(queueFacts);
      pendingActions = (parsed.facts || []).length;
    } catch {}

    reply(msg.chat.id,
      `QC Bot Status\n` +
      `\n` +
      `Session: #${session}\n` +
      `Last task: ${lastTask}\n` +
      `Last completed: ${lastEnd}\n` +
      `Pending actions: ${pendingActions}`
    );
  } catch (err) {
    reply(msg.chat.id, `QC status failed: ${err.message}`);
  }
});

// /qc-redirect <task>
bot.onText(/\/qc-redirect\s+(\S+)/, (msg, match) => {
  if (!isAuthorized(msg)) return;

  const taskClass = match[1].toUpperCase();
  const valid = ['COLLISION_AUDIT', 'DRIFT_CHECK', 'DUPLICATE_SCAN', 'JUNK_DETECTION', 'GRAVITY_WELL_ANALYSIS'];

  if (!valid.includes(taskClass)) {
    reply(msg.chat.id, `Invalid. Options: ${valid.join(', ')}`);
    return;
  }

  try {
    run(`uht-substrate facts upsert "qc-bot" QC_PENDING_DIRECTIVE "TASK:${taskClass}" --namespace CLAUDE`);
    reply(msg.chat.id, `Next QC session will run: ${taskClass}`);
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /qc-pause
bot.onText(/\/qc-pause/, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    run(`uht-substrate facts upsert "qc-bot" QC_PAUSE "true" --namespace CLAUDE`);
    reply(msg.chat.id, 'QC bot paused. Send /qc-resume to restart.');
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /qc-resume
bot.onText(/\/qc-resume/, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    const facts = queryFact('QC_PAUSE');
    const pauseFact = facts.find((f) => f.object === 'true');
    if (pauseFact) {
      run(`uht-substrate facts delete "${pauseFact.uuid}"`);
      reply(msg.chat.id, 'QC bot resumed.');
    } else {
      reply(msg.chat.id, 'QC bot is not paused.');
    }
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /qc-run-now
bot.onText(/\/qc-run-now/, (msg) => {
  if (!isAuthorized(msg)) return;

  exec('systemctl start uht-qc.service', (err) => {
    if (err) {
      reply(msg.chat.id, `QC trigger failed: ${err.message}`);
    } else {
      reply(msg.chat.id, 'QC session triggered. You will get a message when it completes.');
    }
  });
});

// /qc-queue
bot.onText(/\/qc-queue/, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    const out = run(`uht-substrate facts query --predicate QC_ACTION_QUEUE --namespace QUALITY`, 15000);
    const parsed = JSON.parse(out);
    const actions = parsed.facts || [];

    if (actions.length === 0) {
      reply(msg.chat.id, 'No pending QC actions.');
      return;
    }

    const lines = [`Pending QC actions (${actions.length}):\n`];
    for (const a of actions) {
      lines.push(`  ${a.subject}: ${a.object}`);
    }
    lines.push(`\nUse /qc-approve <subject> or /qc-reject <subject>`);
    reply(msg.chat.id, lines.join('\n'));
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /qc-approve all
bot.onText(/\/qc-approve\s+all\b/i, (msg) => {
  if (!isAuthorized(msg)) return;

  try {
    const out = run(`uht-substrate facts query --predicate QC_ACTION_QUEUE --namespace QUALITY`, 15000);
    const parsed = JSON.parse(out);
    const actions = parsed.facts || [];

    if (actions.length === 0) {
      reply(msg.chat.id, 'No pending QC actions.');
      return;
    }

    let approved = 0;
    for (const a of actions) {
      run(`uht-substrate facts store "${a.subject}" QC_ACTION_APPROVED "${a.object.replace(/"/g, '\\"')}" --namespace QUALITY`);
      run(`uht-substrate facts delete "${a.uuid}"`);
      approved++;
    }
    reply(msg.chat.id, `Approved all ${approved} actions. Will execute on next QC session.`);
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /qc-approve <action-subject>
bot.onText(/\/qc-approve\s+(\S+)/, (msg, match) => {
  if (!isAuthorized(msg)) return;

  const actionId = match[1];
  try {
    const out = run(`uht-substrate facts query --predicate QC_ACTION_QUEUE --namespace QUALITY`, 15000);
    const parsed = JSON.parse(out);
    const action = (parsed.facts || []).find((f) => f.subject === actionId);

    if (!action) {
      reply(msg.chat.id, `No queued action with subject: ${actionId}`);
      return;
    }

    // Store as approved, delete from queue
    run(`uht-substrate facts store "${actionId}" QC_ACTION_APPROVED "${action.object.replace(/"/g, '\\"')}" --namespace QUALITY`);
    run(`uht-substrate facts delete "${action.uuid}"`);
    reply(msg.chat.id, `Approved: ${action.object}\nWill execute on next QC session.`);
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /qc-reject <action-subject>
bot.onText(/\/qc-reject\s+(\S+)/, (msg, match) => {
  if (!isAuthorized(msg)) return;

  const actionId = match[1];
  try {
    const out = run(`uht-substrate facts query --predicate QC_ACTION_QUEUE --namespace QUALITY`, 15000);
    const parsed = JSON.parse(out);
    const action = (parsed.facts || []).find((f) => f.subject === actionId);

    if (!action) {
      reply(msg.chat.id, `No queued action with subject: ${actionId}`);
      return;
    }

    run(`uht-substrate facts delete "${action.uuid}"`);
    reply(msg.chat.id, `Rejected and removed: ${action.object}`);
  } catch (err) {
    reply(msg.chat.id, `Failed: ${err.message}`);
  }
});

// /help
bot.onText(/\/help/, (msg) => {
  if (!isAuthorized(msg)) return;

  reply(msg.chat.id,
    `UHT Loop Commands\n` +
    `\n` +
    `/status — current session info\n` +
    `/redirect <task> — set next task (INTEGRITY, TRACE_GAP, CALIBRATION, CORPUS_EXPANSION, APPLICATION)\n` +
    `/reqs — list AIRGen requirements\n` +
    `/expand <domain> — queue corpus expansion\n` +
    `/experiment <desc> — queue a hypothesis for calibration\n` +
    `/pause — pause the loop\n` +
    `/resume — resume the loop\n` +
    `/run-now — trigger a session immediately\n` +
    `\n` +
    `QC Bot Commands\n` +
    `\n` +
    `/qc-status — QC bot state and pending actions\n` +
    `/qc-redirect <task> — set next QC task (COLLISION_AUDIT, DRIFT_CHECK, DUPLICATE_SCAN, JUNK_DETECTION, GRAVITY_WELL_ANALYSIS)\n` +
    `/qc-pause — pause QC bot\n` +
    `/qc-resume — resume QC bot\n` +
    `/qc-run-now — trigger QC session immediately\n` +
    `/qc-queue — list pending QC actions\n` +
    `/qc-approve <id> — approve a queued action\n` +
    `/qc-reject <id> — reject a queued action`
  );
});

bot.on('polling_error', (err) => {
  console.error('Polling error:', err.message);
});

console.log('UHT Loop Telegram bot started');
