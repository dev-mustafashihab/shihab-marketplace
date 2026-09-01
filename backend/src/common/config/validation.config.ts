import { ValidationPipeOptions } from '@nestjs/common';

/**
 * Global DTO validation: unknown fields are whitelisted out, wrong types are
 * transformed when possible, and explicit type coercion is forbidden.
 */
export const validationPipeOptions: ValidationPipeOptions = {
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
  transformOptions: { enableImplicitConversion: false },
  stopAtFirstError: false,
};
