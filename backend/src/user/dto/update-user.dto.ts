import { IsArray, IsEmail, IsInt, IsOptional, IsString } from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsArray()
  @IsInt({ each: true })
  departmentIds?: number[];

  @IsOptional()
  @IsString()
  profileImage?: string | null; // base64-string van profielfoto
}
