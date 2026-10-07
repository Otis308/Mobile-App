import { IsEnum, IsMongoId } from 'class-validator';
export class AddMemberDto { @IsMongoId() userId!: string; @IsEnum(['manager','member']) role!: 'manager'|'member'; }
