import { IsJWT } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RefreshDto {
  @ApiProperty({ description: 'The refresh token obtained from login/register/refresh' })
  @IsJWT({ message: 'refreshToken must be a valid JWT' })
  refreshToken!: string;
}
