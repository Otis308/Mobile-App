import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CommentsService } from './comments.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateCommentDto } from './dto/create-comment.dto';
@Controller('tasks/:taskId/comments') @UseGuards(JwtAuthGuard)
export class CommentsController { constructor(private readonly comments:CommentsService){} @Get() list(@Param('taskId')id:string,@CurrentUser()u:any){return this.comments.list(id,u._id)} @Post() create(@Param('taskId')id:string,@CurrentUser()u:any,@Body()d:CreateCommentDto){return this.comments.create(id,u._id,d)} }
@Controller('comments') @UseGuards(JwtAuthGuard)
export class CommentController { constructor(private readonly comments:CommentsService){} @Delete(':id') remove(@Param('id')id:string,@CurrentUser()u:any){return this.comments.remove(id,u._id)} }
