import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Project, ProjectDocument } from '../projects/schemas/project.schema';
import { Task, TaskDocument } from '../tasks/schemas/task.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { UsersService } from '../users/users.service';
@Injectable()
export class DashboardService {
  constructor(@InjectModel(Project.name) private readonly projects:Model<ProjectDocument>, @InjectModel(Task.name) private readonly tasks:Model<TaskDocument>, private readonly notifications:NotificationsService, private readonly users:UsersService){}
  async summary(userId:string){
    const uid=new Types.ObjectId(userId); const projects=await this.projects.find({'members.userId':uid}).sort({updatedAt:-1}).limit(6).lean();
    const start=new Date(); start.setHours(0,0,0,0); const end=new Date(start); end.setDate(end.getDate()+1);
    const today=await this.tasks.find({projectId:{$in:projects.map((p:any)=>p._id)},dueDate:{$gte:start,$lt:end},status:{$ne:'done'}}).sort({dueDate:1}).lean();
    const completed=await this.tasks.countDocuments({assigneeId:uid,status:'done',updatedAt:{$gte:new Date(Date.now()-7*24*3600*1000)}});
    const assigned=await this.tasks.countDocuments({assigneeId:uid});
    const unread=await this.notifications.unread(userId);
    return {projects,totalProjects:projects.length,todayTasks:today,unreadNotifications:unread,performance:{completedThisWeek:completed,assignedTotal:assigned,completionRate:assigned?Math.round(completed/assigned*100):0}};
  }
}
