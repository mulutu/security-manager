# Security Manager Web Application

Modern SaaS web application for the Security Manager platform, built with Next.js, Prisma, PostgreSQL, and shadcn/ui.

## 🚀 Tech Stack

- **Framework**: Next.js 14 with App Router
- **Language**: TypeScript
- **Database**: PostgreSQL with Prisma ORM
- **Authentication**: NextAuth.js
- **Styling**: Tailwind CSS
- **UI Components**: shadcn/ui
- **Charts**: Recharts
- **Icons**: Lucide React
- **Deployment**: Vercel

## 📁 Project Structure

```
web/
├── src/
│   ├── app/                    # Next.js App Router
│   │   ├── api/               # API routes
│   │   ├── auth/              # Authentication pages
│   │   ├── dashboard/         # Dashboard pages
│   │   └── globals.css        # Global styles
│   ├── components/            # React components
│   │   └── ui/               # shadcn/ui components
│   └── lib/                  # Utility libraries
│       ├── auth.ts           # NextAuth configuration
│       ├── prisma.ts         # Prisma client
│       └── utils.ts          # Utility functions
├── prisma/                   # Database schema and migrations
├── public/                   # Static assets
└── package.json
```

## 🛠️ Features

### ✅ Implemented
- **Modern Landing Page**: Professional SaaS landing page with features, pricing, and CTA
- **Dashboard Layout**: Basic dashboard with overview cards and tabs
- **Authentication Setup**: NextAuth.js with Google and credentials providers
- **Database Schema**: Comprehensive Prisma schema for security management
- **UI Components**: shadcn/ui components for consistent design
- **Responsive Design**: Mobile-first responsive layout

### 🚧 In Development
- **Real-time Dashboard**: Live security events and metrics
- **Alert Management**: Security alert viewing and management
- **Agent Management**: Agent status and configuration
- **User Management**: Organization and user administration
- **API Integration**: Connection to Security Manager engine

## 🚀 Getting Started

### Prerequisites
- Node.js 18+ 
- PostgreSQL database
- Security Manager engine running (optional for development)

### Installation

1. **Clone and navigate to web directory**
   ```bash
   cd web
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   ```bash
   cp env.example .env.local
   ```
   
   Edit `.env.local` with your configuration:
   ```env
   # Database
   DATABASE_URL="postgresql://username:password@localhost:5432/security_manager"
   
   # NextAuth.js
   NEXTAUTH_URL="http://localhost:3000"
   NEXTAUTH_SECRET="your-secret-key-here"
   
   # Security Manager Engine
   SECURITY_ENGINE_URL="http://178.79.139.38:9002"
   CLICKHOUSE_URL="http://178.79.139.38:8123"
   NATS_URL="nats://178.79.139.38:4222"
   ```

4. **Set up database**
   ```bash
   # Generate Prisma client
   npx prisma generate
   
   # Run database migrations
   npx prisma migrate dev
   
   # (Optional) Seed database
   npx prisma db seed
   ```

5. **Start development server**
   ```bash
   npm run dev
   ```

6. **Open your browser**
   Navigate to [http://localhost:3000](http://localhost:3000)

## 📊 Database Schema

The application uses a comprehensive database schema with the following main entities:

### Core Entities
- **Organizations**: Multi-tenant organizations
- **Users**: Organization members with roles
- **Agents**: Security monitoring agents
- **SecurityEvents**: Real-time security events
- **SecurityAlerts**: Triggered security alerts
- **MitigationActions**: Automated response actions
- **SystemMetrics**: Performance metrics
- **DashboardWidgets**: Custom dashboard widgets

### Key Features
- **Multi-tenancy**: Organization-based data isolation
- **Role-based Access**: Admin, User, Viewer roles
- **Real-time Data**: Event streaming and metrics
- **Audit Trail**: Complete action logging
- **Customization**: User-specific dashboard widgets

## 🎨 UI Components

Built with shadcn/ui for consistent, accessible components:

### Available Components
- **Layout**: Cards, Tabs, Badges
- **Forms**: Input, Label, Button
- **Feedback**: Alert, Dialog
- **Navigation**: Dropdown Menu
- **Data**: Table
- **Icons**: Lucide React icons

### Design System
- **Colors**: Slate-based color palette
- **Typography**: Inter font family
- **Spacing**: Consistent spacing scale
- **Responsive**: Mobile-first design

## 🔐 Authentication

### Providers
- **Google OAuth**: Social login
- **Credentials**: Email/password authentication
- **Session Management**: JWT-based sessions

### Features
- **Multi-tenant**: Organization-based access
- **Role-based**: Admin, User, Viewer permissions
- **Secure**: Password hashing with bcrypt
- **Persistent**: Database-backed sessions

## 🚀 Deployment

### Vercel Deployment

1. **Connect to Vercel**
   ```bash
   npm install -g vercel
   vercel login
   ```

2. **Deploy**
   ```bash
   vercel --prod
   ```

3. **Environment Variables**
   Set up environment variables in Vercel dashboard:
   - `DATABASE_URL`
   - `NEXTAUTH_URL`
   - `NEXTAUTH_SECRET`
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`

### Database Setup
- Use Vercel Postgres or external PostgreSQL
- Run migrations: `npx prisma migrate deploy`
- Generate client: `npx prisma generate`

## 🔧 Development

### Available Scripts
```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run start        # Start production server
npm run lint         # Run ESLint
npm run type-check   # Run TypeScript check
```

### Database Commands
```bash
npx prisma studio    # Open database GUI
npx prisma migrate dev    # Create and apply migration
npx prisma generate  # Generate Prisma client
npx prisma db seed   # Seed database (if configured)
```

### Adding Components
```bash
# Add shadcn/ui component
npx shadcn@latest add [component-name]

# Examples
npx shadcn@latest add button
npx shadcn@latest add card
npx shadcn@latest add table
```

## 📈 Roadmap

### Phase 1: Core Dashboard ✅
- [x] Landing page
- [x] Basic dashboard layout
- [x] Authentication system
- [x] Database schema

### Phase 2: Real-time Features 🚧
- [ ] Live security events
- [ ] Real-time alerts
- [ ] Agent status monitoring
- [ ] System metrics charts

### Phase 3: Advanced Features 📋
- [ ] Alert management
- [ ] Agent configuration
- [ ] User management
- [ ] Organization settings

### Phase 4: Enterprise Features 📋
- [ ] Advanced analytics
- [ ] Custom dashboards
- [ ] API integrations
- [ ] Advanced reporting

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is part of the Security Manager platform.

## 🆘 Support

For support and questions:
- Check the documentation
- Open an issue on GitHub
- Contact the development team
