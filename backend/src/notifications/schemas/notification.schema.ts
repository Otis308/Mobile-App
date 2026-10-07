import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';
export type NotificationDocument=HydratedDocument<Notification>;
@Schema({timestamps:true}) export class Notification { @Prop({type:Types.ObjectId,ref:'User',required:true,index:true}) userId!:Types.ObjectId; @Prop({required:true}) type!:string; @Prop({required:true}) message!:string; @Prop() link?:string; @Prop({default:false}) isRead!:boolean; }
export const NotificationSchema=SchemaFactory.createForClass(Notification); NotificationSchema.index({userId:1,isRead:1,createdAt:-1});
