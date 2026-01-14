declare global {
  interface Window {
    google: typeof google;
  }
}

declare namespace google {
  namespace maps {
    class DistanceMatrixService {
      getDistanceMatrix(
        request: DistanceMatrixRequest,
        callback: (response: DistanceMatrixResponse | null, status: DistanceMatrixStatus) => void
      ): void;
    }

    interface DistanceMatrixRequest {
      origins: LatLng[] | string[];
      destinations: LatLng[] | string[];
      travelMode: TravelMode;
      unitSystem: UnitSystem;
      avoidHighways?: boolean;
      avoidTolls?: boolean;
    }

    interface DistanceMatrixResponse {
      rows: DistanceMatrixResponseRow[];
    }

    interface DistanceMatrixResponseRow {
      elements: DistanceMatrixResponseElement[];
    }

    interface DistanceMatrixResponseElement {
      distance?: Distance;
      duration?: Duration;
      status: DistanceMatrixElementStatus;
    }

    interface Distance {
      text: string;
      value: number;
    }

    interface Duration {
      text: string;
      value: number;
    }

    interface LatLng {
      lat: number;
      lng: number;
    }

    enum TravelMode {
      DRIVING = 'DRIVING',
      WALKING = 'WALKING',
      BICYCLING = 'BICYCLING',
      TRANSIT = 'TRANSIT'
    }

    enum UnitSystem {
      METRIC = 0,
      IMPERIAL = 1
    }

    enum DistanceMatrixStatus {
      OK = 'OK',
      INVALID_REQUEST = 'INVALID_REQUEST',
      OVER_QUERY_LIMIT = 'OVER_QUERY_LIMIT',
      REQUEST_DENIED = 'REQUEST_DENIED',
      UNKNOWN_ERROR = 'UNKNOWN_ERROR'
    }

    enum DistanceMatrixElementStatus {
      OK = 'OK',
      NOT_FOUND = 'NOT_FOUND',
      ZERO_RESULTS = 'ZERO_RESULTS'
    }
  }
}

export {};