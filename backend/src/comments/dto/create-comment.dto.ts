import { IsString, Length } from 'class-validator';
export class CreateCommentDto { @IsString() @Length(1,3000) content!:string; }
