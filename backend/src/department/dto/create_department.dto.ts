// src/departments/dto/create-department.dto.ts
import { IsArray, IsInt, IsString, MinLength } from 'class-validator';

export class CreateDepartmentDto {
  @IsString()
  @MinLength(1)
  name: string;

  @IsArray()
  @IsInt({ each: true })
  leaderIds: number[];
}