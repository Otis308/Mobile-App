import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type UserDocument = HydratedDocument<User>;

@Schema({ timestamps: true })
export class User {
  @Prop({ required: true, unique: true, trim: true, lowercase: true }) email!: string;
  @Prop({ required: true, unique: true, trim: true }) username!: string;
  @Prop({ required: true, trim: true }) fullName!: string;
  @Prop({ required: true, select: false }) passwordHash!: string;
  
  @Prop({ trim: true }) phone?: string;
  @Prop({ trim: true }) dob?: string;
  @Prop({ trim: true }) gender?: string;
  @Prop({ enum: ['admin', 'manager', 'member'], default: 'member' }) role!: 'admin' | 'manager' | 'member';
  @Prop() avatarUrl?: string;
  
  @Prop({ default: null }) resetPasswordOtp?: string;
  @Prop({ default: null }) resetPasswordExpires?: Date;
  
  @Prop({ default: null }) lastPasswordReset?: Date;
}

export const UserSchema = SchemaFactory.createForClass(User);
UserSchema.index({ email: 1 }, { unique: true });
UserSchema.index({ username: 1 }, { unique: true });
UserSchema.index({ fullName: 'text', username: 'text', email: 'text' });