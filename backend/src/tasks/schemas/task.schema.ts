import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
export type TaskDocument = HydratedDocument<Task>;
@Schema({ timestamps: true })
export class Task {
  @Prop({ type: Types.ObjectId, ref: 'Project', required: true, index: true }) projectId!: Types.ObjectId;
  @Prop({ required: true, trim: true }) title!: string;
  @Prop({ default: '', trim: true }) description!: string;
  @Prop({ enum: ['low','medium','high','urgent'], default: 'medium' }) priority!: 'low'|'medium'|'high'|'urgent';
  @Prop({ enum: ['todo','doing','review','done'], default: 'todo' }) status!: 'todo'|'doing'|'review'|'done';
  @Prop({ type: Types.ObjectId, ref: 'User' }) assigneeId?: Types.ObjectId;
  @Prop({ type: Types.ObjectId, ref: 'User', required: true }) createdBy!: Types.ObjectId;
  @Prop() dueDate?: Date;
  @Prop({ default: 0 }) order!: number;
  @Prop({ type: [String], default: [] }) labels!: string[];
  @Prop({ type: Date, default: null }) completedAt?: Date | null;
  @Prop({ default: false }) dueReminderSent!: boolean;
}
export const TaskSchema = SchemaFactory.createForClass(Task);
TaskSchema.index({ projectId: 1, status: 1, order: 1 });
TaskSchema.index({ assigneeId: 1, dueDate: 1 });
