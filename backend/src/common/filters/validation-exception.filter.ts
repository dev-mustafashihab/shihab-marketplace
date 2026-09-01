import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';
import { ValidationError } from 'class-validator';
import { Response } from 'express';

interface ValidationBody {
  statusCode: number;
  message: string | string[];
  error?: string;
}

@Catch(ValidationError)
export class ValidationExceptionFilter implements ExceptionFilter {
  catch(exception: ValidationError, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    response.status(400).json({
      success: false,
      message: 'Validation failed',
      code: 'VALIDATION_ERROR',
      errors: this.flatten([exception]),
    });
  }

  private flatten(errors: ValidationError[], parent = ''): { field: string; message: string }[] {
    const out: { field: string; message: string }[] = [];
    for (const e of errors) {
      const field = parent ? `${parent}.${e.property}` : e.property;
      if (e.constraints) {
        for (const msg of Object.values(e.constraints)) {
          out.push({ field, message: msg });
        }
      }
      if (e.children?.length) {
        out.push(...this.flatten(e.children, field));
      }
    }
    return out;
  }
}
