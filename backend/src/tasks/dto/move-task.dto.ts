import { IsEnum, IsInt, Min } from 'class-validator';
export class MoveTaskDto { @IsEnum(['todo','doing','review','done']) status!: 'todo'|'doing'|'review'|'done'; @IsInt() @Min(0) order!: number; }
