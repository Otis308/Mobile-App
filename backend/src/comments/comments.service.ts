import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Comment, CommentDocument } from './schemas/comment.schema';
import { TasksService } from '../tasks/tasks.service';
import { CreateCommentDto } from './dto/create-comment.dto';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class CommentsService {
 constructor(@InjectModel(Comment.name) private readonly model:Model<CommentDocument>,private readonly tasks:TasksService,private readonly realtime:RealtimeGateway){}
 async list(taskId:string,userId:string){await this.tasks.get(taskId,userId);return this.model.find({taskId:new Types.ObjectId(taskId)}).sort({createdAt:1}).lean().exec();}
 async create(taskId:string,userId:string,dto:CreateCommentDto){const task=await this.tasks.get(taskId,userId);const c=await this.model.create({taskId:new Types.ObjectId(taskId),authorId:new Types.ObjectId(userId),content:dto.content});const result=c.toObject();this.realtime.projectRoom(task.projectId.toString(),'comment.created',result);return result;}
 async remove(id:string,userId:string){const c=await this.model.findById(id).lean();if(!c)throw new NotFoundException('Không tìm thấy bình luận');if(c.authorId.toString()!==userId)throw new NotFoundException('Không thể xóa bình luận này');await this.model.findByIdAndDelete(id);return {ok:true};}
}
