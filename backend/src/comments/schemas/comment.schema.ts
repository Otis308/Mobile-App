import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
export type CommentDocument = HydratedDocument<Comment>;
@Schema({ timestamps: true })
export class Comment { @Prop({type:Types.ObjectId,ref:'Task',required:true,index:true}) taskId!:Types.ObjectId; @Prop({type:Types.ObjectId,ref:'User',required:true}) authorId!:Types.ObjectId; @Prop({required:true,trim:true,maxlength:3000}) content!:string; }
export const CommentSchema=SchemaFactory.createForClass(Comment); CommentSchema.index({taskId:1,createdAt:1});
