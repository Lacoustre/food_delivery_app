interface LoaderProps {
  message?: string;
}

export default function Loader({ message }: LoaderProps) {
  return (
    <div className="flex flex-col items-center justify-center w-full h-full text-center">
      <div
        role="status"
        aria-label="Loading"
        className="animate-spin rounded-full h-10 w-10 border-4 border-amber-600 border-t-transparent mb-3"
      />
      {message && (
        <p className="text-sm text-gray-600">{message}</p>
      )}
    </div>
  );
}
