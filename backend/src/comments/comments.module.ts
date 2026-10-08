import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CommentsController } from './comments.controller';
import { CommentsService } from './comments.service';
import { Comment, CommentSchema } from './schemas/comment.schema';
import { TasksModule } from '../tasks/tasks.module';
import { RealtimeModule } from '../realtime/realtime.module';
// 1. Import NotificationsModule
import { NotificationsModule } from '../notifications/notifications.module'; 

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Comment.name, schema: CommentSchema }]),
    TasksModule,
    RealtimeModule,
    NotificationsModule, // 2. Thêm vào mảng imports
  ],
  controllers: [CommentsController],
  providers: [CommentsService],
})
export class CommentsModule {}