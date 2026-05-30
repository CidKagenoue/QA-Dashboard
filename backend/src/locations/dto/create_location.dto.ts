import { IsInt, IsString, MinLength } from 'class-validator';

export class CreateLocationDto {
  @IsString()
  @MinLength(1)
  name: string;

  @IsInt()
  branchId: number;
}
