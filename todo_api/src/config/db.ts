import mongoose from 'mongoose';
import { env } from './env.ts';
import { logger } from '../shared/logger.ts';

export async function connectDatabase(): Promise<void> {
  // Reject queries that use fields not declared in the schema.
  mongoose.set('strictQuery', true);
  await mongoose.connect(env.MONGO_URI);
  logger.info('MongoDB connected');
}

export async function disconnectDatabase(): Promise<void> {
  await mongoose.disconnect();
}
