import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { map, Observable } from 'rxjs';
import { ApiMeta, ApiResponse } from '../envelope.model';

@Injectable()
export class SuccessInterceptor<T> implements NestInterceptor<T, ApiResponse<T>> {
  intercept(context: ExecutionContext, next: CallHandler<T>): Observable<ApiResponse<T>> {
    return next.handle().pipe(
      map((body) => {
        if (body !== null && typeof body === 'object' && 'data' in (body as object) &&
            ('meta' in (body as object) || 'message' in (body as object))) {
          return body as unknown as ApiResponse<T>;
        }
        return { success: true as const, data: body, message: null, meta: {} satisfies ApiMeta };
      }),
    );
  }
}
