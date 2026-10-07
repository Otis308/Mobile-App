import { Module, forwardRef } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Comment, CommentSchema } from './schemas/comment.schema';
import { CommentsService } from './comments.service';
import { CommentsController, CommentController } from './comments.controller';
import { TasksModule } from '../tasks/tasks.module';
import { RealtimeModule } from '../realtime/realtime.module';
@Module({imports:[MongooseModule.forFeature([{name:Comment.name,schema:CommentSchema}]),forwardRef(()=>TasksModule),forwardRef(()=>RealtimeModule)],controllers:[CommentsController,CommentController],providers:[CommentsService]}) export class CommentsModule {}
