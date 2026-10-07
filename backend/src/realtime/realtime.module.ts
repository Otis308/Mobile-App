import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RealtimeGateway } from './realtime.gateway';
import { Project, ProjectSchema } from '../projects/schemas/project.schema';
@Module({ imports:[MongooseModule.forFeature([{name:Project.name,schema:ProjectSchema}])], providers:[RealtimeGateway], exports:[RealtimeGateway] }) export class RealtimeModule {}
