import { Body, Controller, Delete, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ProjectsService } from './projects.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateProjectDto } from './dto/create-project.dto';
import { UpdateProjectDto } from './dto/update-project.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { UsersService } from '../users/users.service';

@Controller('projects')
@UseGuards(JwtAuthGuard)
export class ProjectsController {
  constructor(private readonly projects: ProjectsService, private readonly users: UsersService) {}
  @Get() list(@CurrentUser() u:any) { return this.projects.listForUser(u._id); }
  @Get('search-user') async searchUser(@Query('q') q='') { return this.users.search(q); }
  @Post() create(@CurrentUser() u:any,@Body() dto:CreateProjectDto){return this.projects.create(u._id,dto);}
  @Get(':id') get(@Param('id') id:string,@CurrentUser() u:any){return this.projects.member(id,u._id).then(x=>x.project);}
  @Put(':id') update(@Param('id') id:string,@CurrentUser() u:any,@Body() dto:UpdateProjectDto){return this.projects.update(id,u._id,dto);}
  @Delete(':id') removeProject(@Param('id') id:string,@CurrentUser() u:any){return this.projects.removeProject(id,u._id);}
  @Get(':id/members') async members(@Param('id') id:string,@CurrentUser() u:any){const {project}=await this.projects.member(id,u._id); return this.users.sanitizeMany(project.members.map((m:any)=>m.userId.toString()));}
  @Post(':id/members') add(@Param('id') id:string,@CurrentUser() u:any,@Body() dto:AddMemberDto){return this.projects.addMember(id,u._id,dto);}
  @Delete(':id/members/:userId') remove(@Param('id') id:string,@Param('userId') userId:string,@CurrentUser() u:any){return this.projects.removeMember(id,u._id,userId);}
}
