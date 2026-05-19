import { PartialType } from '@nestjs/mapped-types';
import { CreateDepartmentDto } from './create_department.dto';

export class UpdateDepartmentDto extends PartialType(CreateDepartmentDto) {}