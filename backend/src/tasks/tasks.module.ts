import { Module, forwardRef } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Task, TaskSchema } from './schemas/task.schema';
import { TasksService } from './tasks.service';
import { TasksController, ProjectTasksController } from './tasks.controller';
import { ProjectsModule } from '../projects/projects.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { DeadlineReminderService } from './deadline-reminder.service';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Task.name, schema: TaskSchema }]),
    forwardRef(() => ProjectsModule),
    NotificationsModule,
    forwardRef(() => RealtimeModule),
  ],
  controllers: [
    TasksController, 
    ProjectTasksController
  ],
  providers: [TasksService,DeadlineReminderService],
  exports: [
    TasksService, 
    MongooseModule
  ],
})
export class TasksModule {}