// src/department/department.dto.ts
export class CreateDepartmentDto {
  name: string;
  leaderIds: number[]; // user IDs
}

export class UpdateDepartmentDto {
  name?: string;
  leaderIds?: number[];
}
