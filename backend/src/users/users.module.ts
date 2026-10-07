import { Module, Global } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { User, UserSchema } from './schemas/user.schema';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { JwtModule } from '@nestjs/jwt';

@Global() // Phép thuật nằm ở dòng này: Biến module thành toàn cục
@Module({ 
  imports: [
    MongooseModule.forFeature([{ name: User.name, schema: UserSchema }]), 
    JwtModule
  ], 
  controllers: [UsersController], 
  providers: [UsersService], 
  exports: [UsersService] 
})
export class UsersModule {}
