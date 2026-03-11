import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const posts = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/posts' }),
  schema: z.object({
    title: z.string(),
    date: z.string(),
    time: z.string().optional(),
    session: z.string(),
    session_type: z.enum(['autonomous', 'human']),
    task_class: z.string().optional(),
    status: z.enum(['published', 'draft']),
  }),
});

export const collections = { posts };
