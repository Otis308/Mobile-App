import { Module, forwardRef } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Project, ProjectSchema } from './schemas/project.schema';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';
import { UsersModule } from '../users/users.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
@Module({ imports:[MongooseModule.forFeature([{name:Project.name,schema:ProjectSchema}]), UsersModule, NotificationsModule, forwardRef(()=>RealtimeModule)], controllers:[ProjectsController], providers:[ProjectsService], exports:[ProjectsService] })
export class ProjectsModule {}
