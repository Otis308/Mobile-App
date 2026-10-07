import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { TasksService } from './tasks.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateTaskDto } from './dto/create-task.dto';
import { UpdateTaskDto } from './dto/update-task.dto';
import { MoveTaskDto } from './dto/move-task.dto';
@Controller('projects/:projectId/tasks') @UseGuards(JwtAuthGuard)
export class ProjectTasksController { constructor(private readonly tasks:TasksService){} @Get() list(@Param('projectId') p:string,@CurrentUser()u:any){return this.tasks.list(p,u._id)} @Post() create(@Param('projectId')p:string,@CurrentUser()u:any,@Body()d:CreateTaskDto){return this.tasks.create(p,u._id,d)} }
@Controller('tasks') @UseGuards(JwtAuthGuard)
export class TasksController { constructor(private readonly tasks:TasksService){} @Get(':id') get(@Param('id')id:string,@CurrentUser()u:any){return this.tasks.get(id,u._id)} @Patch(':id') update(@Param('id')id:string,@CurrentUser()u:any,@Body()d:UpdateTaskDto){return this.tasks.update(id,u._id,d)} @Patch(':id/move') move(@Param('id')id:string,@CurrentUser()u:any,@Body()d:MoveTaskDto){return this.tasks.move(id,u._id,d)} @Delete(':id') remove(@Param('id')id:string,@CurrentUser()u:any){return this.tasks.remove(id,u._id)} }
