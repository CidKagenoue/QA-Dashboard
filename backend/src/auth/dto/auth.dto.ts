export class LoginDto {
  email: string;
  password: string;
}

export class RefreshTokenDto {
  refreshToken: string;
}

export class ForgotPasswordDto {
  email: string;
}

export class VerifyResetTokenDto {
  token: string;
}

export class ResetPasswordDto {
  token: string;
  password: string;
  confirmPassword: string;
}