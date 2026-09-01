import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR, APP_PIPE } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { ValidationPipe } from '@nestjs/common';
import { HealthController } from './app.controller';
import { envValidationSchema } from './common/config/env.validation';
import { validationPipeOptions } from './common/config/validation.config';
import { PrismaModule } from './common/prisma.module';
import { SuccessInterceptor } from './common/interceptors/success.interceptor';
import { ApiExceptionFilter } from './common/filters/api-exception.filter';
import { PermissionsGuard } from './common/guards/permissions.guard';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { RolesModule } from './modules/roles/roles.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { VendorsModule } from './modules/vendors/vendors.module';
import { ServicesModule } from './modules/services/services.module';
import { ProductsModule } from './modules/products/products.module';
import { ResourcesModule } from './modules/resources/resources.module';
import { AvailabilityModule } from './modules/availability/availability.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validationSchema: envValidationSchema,
      validationOptions: { abortEarly: false },
    }),
    ThrottlerModule.forRoot([
      {
        name: 'default',
        ttl: Number(process.env.THROTTLE_TTL ?? 60000),
        limit: Number(process.env.THROTTLE_LIMIT ?? 60),
      },
    ]),
    PrismaModule,
    AuthModule,
    UsersModule,
    RolesModule,
    CategoriesModule,
    VendorsModule,
    ServicesModule,
    ProductsModule,
    ResourcesModule,
    AvailabilityModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_PIPE, useValue: new ValidationPipe(validationPipeOptions) },
    // Order matters: authentication must run BEFORE throttling and RBAC
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
    { provide: APP_INTERCEPTOR, useClass: SuccessInterceptor },
    { provide: APP_FILTER, useClass: ApiExceptionFilter },
  ],
})
export class AppModule {}
