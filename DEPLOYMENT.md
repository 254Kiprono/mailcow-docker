# Mailcow Deployment Guide

## Overview
This guide covers deploying Mailcow integrated with the existing e-commerce infrastructure.

## Architecture
- **Database**: Uses existing `hkup-db-service` (MySQL)
- **Cache**: Uses existing `redis-ec` 
- **Web Proxy**: Uses existing `nginx-ec` for external access
- **Network**: Connected to `e-c-deployerscript_e-commerce-network`

## Database Configuration
The mailcow database is already created with these credentials:

```sql
-- Database: mailcow
-- User: mailco-user
-- Password: pass1234!
```

## Pre-Deployment Checklist

### 1. Ensure E-Commerce Stack is Running
```bash
cd /path/to/e-c-deployerscript
docker-compose ps
# Verify these services are running:
# - hkup-db-service
# - redis-ec
# - nginx-ec
```

### 2. Verify Database
```bash
docker exec -it hkup-db-service mysql -u mailco-user -p
# Password: pass1234!

# Run in MySQL:
USE mailcow;
SHOW TABLES;  # Should be empty initially
```

### 3. DNS Configuration
Ensure these DNS records point to your server:
- `mailcow.devsinkenya.com` → Your Server IP
- `mail-admin.devsinkenya.com` → Your Server IP

### 4. Port Requirements
Mailcow requires these ports (already configured in docker-compose):
- **25** - SMTP
- **465** - SMTPS
- **587** - Submission
- **143** - IMAP
- **993** - IMAPS
- **110** - POP3
- **995** - POP3S
- **4190** - Sieve

Note: Ports 80, 443, 3306, and 6379 are NOT used (using existing services)

## Deployment Steps

### Option 1: Automated Deployment (Recommended)
```bash
cd /path/to/mailcow-docker
chmod +x deploy-mailcow.sh
./deploy-mailcow.sh
```

The script will:
1. Check prerequisites
2. Generate environment configuration
3. Verify database connectivity
4. Setup SSL certificates
5. Pull Docker images
6. Start services
7. Display access information

### Option 2: Manual Deployment

#### Step 1: Create Environment Configuration
```bash
cd /path/to/mailcow-docker
cp mailcow.conf.example mailcow.conf

# Generate API keys
sed -i "s/GENERATE_ON_SERVER/$(openssl rand -hex 16)/g" mailcow.conf
```

#### Step 2: Setup SSL Certificates
```bash
chmod +x setup-ssl.sh
./setup-ssl.sh
# Choose option 1: Use existing nginx-ec certificates
```

#### Step 3: Pull Images
```bash
docker-compose pull
```

#### Step 4: Start Services
```bash
docker-compose up -d
```

#### Step 5: Monitor Startup
```bash
docker-compose logs -f
# Press Ctrl+C to exit logs
```

## Post-Deployment Configuration

### Access Mailcow Admin UI
1. Navigate to: `https://mailcow.devsinkenya.com`
2. Default credentials:
   - **Username**: `admin`
   - **Password**: `moohoo`
3. **IMPORTANT**: Change the password immediately!

### Initial Setup Tasks

#### 1. Change Admin Password
```
Login → Admin → Edit Administrator → Change password
```

#### 2. Configure Domain
```
Configuration → Mail setup → Domains → Add domain
Domain: devsinkenya.com
```

#### 3. Add Mailboxes
```
Configuration → Mail setup → Mailboxes → Add mailbox
Example: admin@devsinkenya.com
```

#### 4. Configure DNS Records
Add these DNS records for your domain:

```
# MX Record
devsinkenya.com.    IN  MX  10  mailcow.devsinkenya.com.

# SPF Record
devsinkenya.com.    IN  TXT "v=spf1 mx ~all"

# DKIM (Generated in Mailcow UI)
# Configuration → Configuration & Details → Configuration → ARC/DKIM keys
# Copy the generated DKIM record

# DMARC
_dmarc.devsinkenya.com.  IN  TXT "v=DMARC1; p=quarantine; rua=mailto:postmaster@devsinkenya.com"
```

## SSL Certificate Management

### Using Existing Certificates (Current Setup)
Mailcow uses the same SSL certificates as `nginx-ec`:
```bash
# Certificates are shared from e-c-deployerscript/cert/
# - origin.pem (certificate)
# - private.key (private key)
```

### Setting up Let's Encrypt (Future)
To enable automatic SSL renewal:

1. Update `mailcow.conf`:
```bash
SKIP_LETS_ENCRYPT=n
ADDITIONAL_SAN=mail-admin.devsinkenya.com
```

2. Restart acme-mailcow:
```bash
docker-compose restart acme-mailcow
```

3. Monitor certificate generation:
```bash
docker-compose logs -f acme-mailcow
```

## Monitoring & Maintenance

### Check Service Status
```bash
cd /path/to/mailcow-docker
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f postfix-mailcow
docker-compose logs -f dovecot-mailcow
docker-compose logs -f sogo-mailcow
```

### Restart Services
```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart postfix-mailcow
```

### Stop Services
```bash
docker-compose down
```

### Update Mailcow
```bash
docker-compose pull
docker-compose up -d
```

## Troubleshooting

### Issue: Cannot connect to database
**Check:**
```bash
# Verify hkup-db-service is running
docker ps | grep hkup-db-service

# Test database connection
docker exec -it hkup-db-service mysql -u mailco-user -ppass1234! -e "USE mailcow; SHOW TABLES;"
```

### Issue: Cannot access web UI
**Check:**
```bash
# Verify nginx-ec is running
docker ps | grep nginx-ec

# Check nginx configuration
docker exec -it nginx-ec nginx -t

# Restart nginx-ec
cd /path/to/e-c-deployerscript
docker-compose restart nginx-services
```

### Issue: Email not sending/receiving
**Check:**
```bash
# Check postfix logs
docker-compose logs postfix-mailcow | tail -50

# Check dovecot logs
docker-compose logs dovecot-mailcow | tail -50

# Verify ports are open
netstat -tulpn | grep -E ":(25|465|587|143|993)"
```

### Issue: Services not starting
**Check:**
```bash
# Check all container statuses
docker-compose ps

# Check specific container logs
docker-compose logs [service-name]

# Verify network connectivity
docker network inspect e-c-deployerscript_e-commerce-network
```

## Service Architecture

### Disabled Services (Using External)
These Mailcow services are disabled (using e-commerce stack):
- ❌ `mysql-mailcow` → Using `hkup-db-service`
- ❌ `redis-mailcow` → Using `redis-ec`

### Active Internal Services
- ✅ `nginx-mailcow` - Internal web server (proxied via nginx-ec)
- ✅ `postfix-mailcow` - SMTP server
- ✅ `dovecot-mailcow` - IMAP/POP3 server
- ✅ `sogo-mailcow` - Webmail interface
- ✅ `rspamd-mailcow` - Spam filter
- ✅ `clamd-mailcow` - Antivirus
- ✅ `php-fpm-mailcow` - PHP processor
- ✅ `unbound-mailcow` - DNS resolver
- ✅ `acme-mailcow` - SSL certificate manager
- ✅ `watchdog-mailcow` - Service monitor
- ✅ `olefy-mailcow` - Macro scanner
- ✅ `ofelia-mailcow` - Cron scheduler

### External Links
Services connect to external containers via:
```yaml
external_links:
  - hkup-db-service:mysql  # Database
  - redis-ec:redis         # Cache
```

## Backup & Recovery

### Backup Mailcow Data
```bash
cd /path/to/mailcow-docker

# Backup volumes
docker run --rm \
  -v mailcow-dockerized_vmail-vol-1:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/vmail-$(date +%Y%m%d).tar.gz /data

# Backup database
docker exec hkup-db-service mysqldump -u mailco-user -ppass1234! mailcow > backups/mailcow-db-$(date +%Y%m%d).sql
```

### Restore from Backup
```bash
# Restore database
docker exec -i hkup-db-service mysql -u mailco-user -ppass1234! mailcow < backups/mailcow-db-YYYYMMDD.sql

# Restore volumes
docker run --rm \
  -v mailcow-dockerized_vmail-vol-1:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/vmail-YYYYMMDD.tar.gz -C /
```

## Security Considerations

1. **Change Default Password**: Immediately after first login
2. **Firewall Rules**: Ensure only required ports are open
3. **SSL Certificates**: Keep certificates up to date
4. **Regular Updates**: Update Mailcow images regularly
5. **Backup Strategy**: Implement automated backups
6. **Monitor Logs**: Regularly check for suspicious activity
7. **Two-Factor Auth**: Enable 2FA for admin accounts (available in UI)

## Useful Commands

```bash
# Check Mailcow version
docker-compose version

# View resource usage
docker stats

# Clean up unused images
docker image prune -a

# Export configuration
docker-compose config > mailcow-config-export.yml

# Check mail queue
docker-compose exec postfix-mailcow mailq

# Test SMTP
docker-compose exec postfix-mailcow telnet localhost 25
```

## Support & Resources

- **Mailcow Documentation**: https://docs.mailcow.email/
- **Community Forum**: https://community.mailcow.email/
- **GitHub Issues**: https://github.com/mailcow/mailcow-dockerized/issues
- **Your Admin Panel**: https://mailcow.devsinkenya.com

## Notes
- All services run on the shared `e-c-deployerscript_e-commerce-network`
- No port conflicts with existing services
- Database and Redis are shared resources
- SSL certificates are managed through nginx-ec
- Mailcow admin interface is proxied through nginx-ec
