# RehabTrack - Therapist Dashboard

A Next.js frontend application for physical therapists to monitor patient exercise adherence and quality in real-time.

## Features

- **Secure Authentication**: JWT-based authentication system
- **Patient Management**: Comprehensive patient profiles and exercise tracking
- **Real-time Analytics**: Interactive charts showing adherence and quality metrics
- **Alert System**: Automated alerts for missed sessions, poor form, and safety concerns
- **Progress Tracking**: Visual progress charts and quality metrics
- **Professional UI**: Clean, responsive design with Tailwind CSS

## Tech Stack

- **Next.js 14**: React framework with TypeScript
- **Tailwind CSS**: Utility-first CSS framework
- **Recharts**: Interactive charts and data visualization
- **Axios**: HTTP client for API communication
- **Heroicons**: Beautiful SVG icons
- **date-fns**: Date manipulation and formatting

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- Backend API running on localhost:4000

### Installation

1. Install dependencies:
```bash
npm install
```

2. Create environment file:
```bash
cp .env.local.example .env.local
```

3. Configure environment variables in `.env.local`:
```bash
NEXT_PUBLIC_API_URL=http://localhost:4000
```

4. Start the development server:
```bash
npm run dev
```

The application will be available at `http://localhost:3000`.

### Demo Credentials

- **Therapist**: therapist@example.com / password123
- **Admin**: admin@example.com / password123

## Project Structure

```
frontend/
├── components/           # Reusable UI components
│   ├── Layout.tsx       # Main layout wrapper
│   ├── PatientCard.tsx  # Patient summary card
│   ├── ExerciseChart.tsx # Progress visualization
│   └── QualityMetrics.tsx # Quality analysis display
├── pages/               # Next.js pages
│   ├── index.tsx        # Login page
│   ├── dashboard.tsx    # Main dashboard
│   ├── alerts.tsx       # Alert management
│   └── patient/[id].tsx # Patient detail view
├── services/           # API services
│   └── api.ts          # Backend API client
├── types/              # TypeScript definitions
├── utils/              # Utility functions
└── styles/             # Global styles
```

## Key Components

### Authentication (`utils/auth.ts`)
- JWT token management
- Automatic token refresh
- Route protection with `requireAuth` HOC

### API Service (`services/api.ts`)
- Centralized API client with Axios
- Automatic authentication headers
- Error handling and token refresh

### Layout (`components/Layout.tsx`)
- Responsive sidebar navigation
- User profile management
- Notification system

### Charts (`components/ExerciseChart.tsx`)
- Line charts for progress tracking
- Bar charts for session data
- Area charts for adherence trends

## Pages

### 1. Login (`/`)
- Secure authentication form
- Demo credentials display
- Automatic redirect for authenticated users

### 2. Dashboard (`/dashboard`)
- Overview statistics
- Recent patients
- Alert summaries
- Quick action buttons

### 3. Patient Detail (`/patient/[id]`)
- Patient profile information
- Exercise session history
- Quality metrics analysis
- Progress charts
- Feedback system

### 4. Alerts (`/alerts`)
- Alert filtering and sorting
- Bulk alert management
- Real-time status updates
- Patient navigation

## API Integration

The frontend communicates with the Elixir backend through:

- **Authentication**: POST `/api/auth/login`, GET `/api/auth/me`
- **Patients**: GET `/api/patients`, GET `/api/patients/:id`
- **Sessions**: GET `/api/patients/:id/sessions`
- **Analytics**: GET `/api/patients/:id/adherence`, GET `/api/patients/:id/quality`
- **Alerts**: GET `/api/alerts`, PUT `/api/alerts/:id/acknowledge`

## Development

### Scripts

```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run start        # Start production server
npm run lint         # Run ESLint
npm run type-check   # Run TypeScript compiler
```

### Code Style

- **TypeScript**: Strict typing enabled
- **ESLint**: Next.js recommended rules
- **Prettier**: Code formatting (configured in IDE)
- **Component Structure**: Functional components with hooks

### State Management

- React hooks for local state
- API service for server state
- localStorage for authentication persistence

## Deployment

### Production Build

```bash
npm run build
npm run start
```

### Environment Variables

Required for production:
```bash
NEXT_PUBLIC_API_URL=https://api.rehabtrack.com
NODE_ENV=production
```

### Docker Support

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
```

## Security Features

- JWT token validation
- Secure authentication flow
- HTTPS enforcement in production
- CSRF protection via SameSite cookies
- Input sanitization

## Performance

- Next.js optimizations (SSR, code splitting)
- Image optimization
- Bundle analysis with `@next/bundle-analyzer`
- CDN-ready static assets

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## Contributing

1. Follow TypeScript strict mode
2. Use functional components with hooks
3. Implement proper error handling
4. Add loading states for async operations
5. Ensure responsive design
6. Write meaningful commit messages

## License

This project is part of the RehabTrack rehabilitation exercise tracking system.