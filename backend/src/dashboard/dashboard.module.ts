import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Project, ProjectSchema } from '../projects/schemas/project.schema';
import { Task, TaskSchema } from '../tasks/schemas/task.schema';
import { DashboardController } from './dashboard.controller';
import { DashboardService } from './dashboard.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { UsersModule } from '../users/users.module';
@Module({imports:[MongooseModule.forFeature([{name:Project.name,schema:ProjectSchema},{name:Task.name,schema:TaskSchema}]),NotificationsModule,UsersModule],controllers:[DashboardController],providers:[DashboardService]}) export class DashboardModule {}
