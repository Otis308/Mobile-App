import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
export type ProjectDocument = HydratedDocument<Project>;

@Schema({ _id: false })
export class ProjectMember { @Prop({ type: Types.ObjectId, ref: 'User', required: true }) userId!: Types.ObjectId; @Prop({ enum: ['owner', 'manager', 'member'], default: 'member' }) role!: 'owner'|'manager'|'member'; @Prop({ default: Date.now }) joinedAt!: Date; }
const ProjectMemberSchema = SchemaFactory.createForClass(ProjectMember);

@Schema({ timestamps: true })
export class Project {
  @Prop({ required: true, trim: true }) name!: string;
  @Prop({ default: '', trim: true }) description!: string;
  @Prop({ default: '3E6FF2' }) color!: string;
  @Prop({ type: Types.ObjectId, ref: 'User', required: true }) ownerId!: Types.ObjectId;
  @Prop({ type: [ProjectMemberSchema], default: [] }) members!: ProjectMember[];
}
export const ProjectSchema = SchemaFactory.createForClass(Project);
ProjectSchema.index({ ownerId: 1 });
ProjectSchema.index({ 'members.userId': 1 });
