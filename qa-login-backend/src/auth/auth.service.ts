import {
  Injectable,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import { UserService } from '../user/user.service';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
import { LoginDto } from './dto/auth.dto';

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(private userService: UserService) {}

  async onModuleInit() {
    await this.ensureDefaultAdmin();
  }

  async login(loginDto: LoginDto) {
    const { email, password } = loginDto;

    console.log('Login attempt for email:', email);

    // Find user
    const user = await this.userService.findByEmail(email);
    if (!user) {
      console.log('User not found for email:', email);
      throw new UnauthorizedException('Invalid email or password');
    }

    console.log('User found, verifying password...');

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      console.log('Invalid password for email:', email);
      throw new UnauthorizedException('Invalid email or password');
    }

    console.log('Login successful for email:', email);

    // Generate JWT token
    const token = this.generateToken(user.id, user.email);

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
      token,
    };
  }

  private generateToken(userId: number, email: string): string {
    return jwt.sign(
      { sub: userId, email },
      process.env.JWT_SECRET || 'dev_secret_change_me',
      { expiresIn: '7d' }
    );
  }

  async verifyToken(token: string) {
    try {
      return jwt.verify(token, process.env.JWT_SECRET || 'dev_secret_change_me');
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }

  private async ensureDefaultAdmin() {
    const existingAdmin = await this.userService.findByEmail('admin');
    if (existingAdmin) {
      return;
    }

    const hashedPassword = await bcrypt.hash('root123', 12);
    await this.userService.create({
      email: 'admin',
      password: hashedPassword,
      name: 'Administrator',
    });
  }
}