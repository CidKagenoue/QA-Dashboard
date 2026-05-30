export class UpdateUserDto {
  name?: string;
  email?: string;
  departmentIds?: number[];
  profileImage?: string | null; // base64-string van profielfoto
}
