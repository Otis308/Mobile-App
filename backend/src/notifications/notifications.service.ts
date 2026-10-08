import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Notification, NotificationDocument } from './schemas/notification.schema';
@Injectable() 
    export class NotificationsService { 
        constructor(@InjectModel(Notification.name) private readonly model:Model<NotificationDocument>){}
        async create(userId:string,type:string,message:string,link?:string){return this.model.create({userId:new Types.ObjectId(userId),type,message,link})} 
        async list(userId:string){return this.model.find({userId:new Types.ObjectId(userId)}).sort({createdAt:-1}).limit(30).lean().exec()} 
        async markRead(id:string,userId:string){return this.model.findOneAndUpdate({_id:id,userId:new Types.ObjectId(userId)},{isRead:true},{new:true}).lean().exec()} 
        async unread(userId:string){return this.model.countDocuments({userId:new Types.ObjectId(userId),isRead:false})}
        async markAllRead(userId: string) {
            await this.model.updateMany({ userId: new Types.ObjectId(userId), isRead: false }, { isRead: true });
            return { ok: true };
        }
}
