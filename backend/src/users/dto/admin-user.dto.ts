import { IsEnum, IsOptional } from 'class-validator';
export class AdminUserDto { @IsOptional() @IsEnum(['admin','manager','member']) role?: 'admin'|'manager'|'member'; }
