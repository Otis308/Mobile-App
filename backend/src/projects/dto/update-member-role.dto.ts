import { IsEnum } from 'class-validator';
export class UpdateMemberRoleDto {
  @IsEnum(['manager', 'member']) role!: 'manager' | 'member';
}

