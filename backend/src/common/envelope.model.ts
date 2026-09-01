export interface ApiMeta {
  page?: number;
  limit?: number;
  total?: number;
  totalPages?: number;
  [key: string]: unknown;
}

export interface ApiResponse<T = unknown> {
  success: true;
  data: T;
  message: string | null;
  meta: ApiMeta | Record<string, never>;
}

export interface ApiError {
  success: false;
  message: string;
  code: string;
  errors: { field?: string; message: string }[];
}
