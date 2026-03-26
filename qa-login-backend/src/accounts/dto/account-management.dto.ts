export class CreateAccountDto {
  email!: string;
  password!: string;
  name?: string;
  departmentIds?: number[];
  isAdmin?: boolean;
  basisAccess?: boolean;
  whsToursAccess?: boolean;
  ovaAccess?: boolean;
  japGppAccess?: boolean;
  maintenanceInspectionsAccess?: boolean;
}

export class UpdateAccountAccessDto {
  isAdmin?: boolean;
  basisAccess?: boolean;
  whsToursAccess?: boolean;
  ovaAccess?: boolean;
  japGppAccess?: boolean;
  maintenanceInspectionsAccess?: boolean;
}
