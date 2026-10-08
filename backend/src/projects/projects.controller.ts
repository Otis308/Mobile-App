import { 
  Body, 
  Controller, 
  Delete, 
  Get, 
  Param, 
  Post, 
  Put, 
  Query, 
  UseGuards, 
  Patch 
} from '@nestjs/common';
import { ProjectsService } from './projects.service';
import { UsersService } from '../users/users.service';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateProjectDto } from './dto/create-project.dto';
import { UpdateProjectDto } from './dto/update-project.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { UpdateMemberRoleDto } from './dto/update-member-role.dto';

@UseGuards(JwtAuthGuard)
@Controller('projects')
export class ProjectsController {
  constructor(
    private readonly projectsService: ProjectsService,
    private readonly usersService: UsersService,
  ) {}

  @Get()
  list(@CurrentUser() user: any) {
    return this.projectsService.listForUser(user._id);
  }

  @Get('search-user')
  async searchUser(@Query('q') query = '') {
    return this.usersService.search(query);
  }

  @Post()
  create(@CurrentUser() user: any, @Body() dto: CreateProjectDto) {
    return this.projectsService.create(user._id, dto);
  }

  @Get(':id')
  async get(@Param('id') id: string, @CurrentUser() user: any) {
    const result = await this.projectsService.member(id, user._id);
    return result.project;
  }

  @Put(':id')
  update(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: UpdateProjectDto,
  ) {
    return this.projectsService.update(id, user._id, dto);
  }

  @Delete(':id')
  removeProject(@Param('id') id: string, @CurrentUser() user: any) {
    return this.projectsService.removeProject(id, user._id);
  }

  @Get(':id/members')
  async members(@Param('id') id: string, @CurrentUser() user: any) {
    const { project } = await this.projectsService.member(id, user._id);
    const memberIds = project.members.map((m: any) => m.userId.toString());
    
    return this.usersService.sanitizeMany(memberIds);
  }

  @Post(':id/members')
  add(
    @Param('id') id: string,
    @CurrentUser() user: any,
    @Body() dto: AddMemberDto,
  ) {
    return this.projectsService.addMember(id, user._id, dto);
  }

  @Patch(':id/members/:userId')
  updateRole(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @CurrentUser() user: any,
    @Body() dto: UpdateMemberRoleDto,
  ) {
    return this.projectsService.updateMemberRole(id, user._id, userId, dto);
  }

  @Delete(':id/members/:userId')
  remove(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @CurrentUser() user: any,
  ) {
    return this.projectsService.removeMember(id, user._id, userId);
  }
}