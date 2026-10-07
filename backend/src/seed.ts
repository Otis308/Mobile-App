import 'reflect-metadata';
import { ConfigModule } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { UsersService } from './users/users.service';
import { ProjectsService } from './projects/projects.service';
import { TasksService } from './tasks/tasks.service';

async function seed(){
  ConfigModule.forRoot({isGlobal:true});
  const app=await NestFactory.createApplicationContext(AppModule,{logger:false});
  const users=app.get(UsersService); const projects=app.get(ProjectsService); const tasks=app.get(TasksService);
  const existing=await users.findByEmailOrUsername('admin@example.com');
  const admin=existing ?? await users.create({email:'admin@example.com',username:'admin',fullName:'Quản trị viên',passwordHash:await (await import('bcrypt')).hash('Admin@12345',12),role:'admin'});
  const existingProjects=await projects.listForUser(admin._id.toString());
  let project=existingProjects[0]; if(!project) project=await projects.create(admin._id.toString(),{name:'Dự án mẫu',description:'Không gian làm việc mẫu để kiểm tra ứng dụng',color:'3E6FF2'});
  const current=await tasks.list(project._id.toString(),admin._id.toString());
  if(!current.length){ await tasks.create(project._id.toString(),admin._id.toString(),{title:'Thiết kế luồng đăng nhập',description:'Kiểm tra UX và validation',priority:'high',status:'todo',dueDate:new Date(Date.now()+86400000*2).toISOString(),labels:['UX','Auth']}); await tasks.create(project._id.toString(),admin._id.toString(),{title:'Xây dựng API Task',description:'CRUD và Socket.IO',priority:'urgent',status:'doing',labels:['Backend']}); await tasks.create(project._id.toString(),admin._id.toString(),{title:'Review mobile UI',description:'Kiểm tra Dark Mode và responsive',priority:'medium',status:'review',dueDate:new Date().toISOString(),labels:['Flutter']}); await tasks.create(project._id.toString(),admin._id.toString(),{title:'Viết README chạy local',description:'Docker MongoDB + backend + mobile',priority:'low',status:'done',labels:['Docs']}); }
  console.log('Seed hoàn tất. Tài khoản: admin@example.com / Admin@12345'); await app.close();
}
seed().catch(err=>{console.error(err);process.exit(1)});
