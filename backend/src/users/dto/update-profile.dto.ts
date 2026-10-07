import { IsOptional, IsString, Length } from 'class-validator';
export class UpdateProfileDto {
  @IsOptional() @IsString() @Length(2, 80) fullName?: string;
  @IsOptional() @IsString() @Length(3, 40) username?: string;
}
