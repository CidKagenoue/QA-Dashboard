export class UpdateUserDto {
  name?: string;
  email?: string;
  departmentIds?: number[];
  profileImage?: string; // base64-string van profielfoto
}
