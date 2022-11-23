# Laravel application container

- [Laravel application container](#laravel-application-container)
  - [Chuẩn bị Laravel source code](#chuẩn-bị-laravel-source-code)
    - [Chuẩn bị php và composer](#chuẩn-bị-php-và-composer)
    - [Chuẩn bị docker volume](#chuẩn-bị-docker-volume)
    - [Tạo project laravel](#tạo-project-laravel)
  - [Chuẩn bị docker-compose file](#chuẩn-bị-docker-compose-file)
    - [Một số lưu ý](#một-số-lưu-ý)
  - [Khởi động ứng dụng](#khởi-động-ứng-dụng)
  - [Kiểm tra kết nối database từ application vào database server](#kiểm-tra-kết-nối-database-từ-application-vào-database-server)

Trong project này mình sẽ thực hiện chạy 1 ứng dụng laravel bằng container, sử dụng LEMP (Linux, Nginx, MySQL, PHP-FPM). Toàn bộ các thành phần này sẽ được chạy riêng biệt trên từng container khác nhau

## Chuẩn bị Laravel source code

Trong project này mình sẽ tạo mới và dùng 1 laravel project mặc định của laravel

Tất nhiên bạn cũng có thể dùng source code có sẵn của chính mình và chỉ cần mount volume source path vào bên trong các container để sử dụng

### Chuẩn bị php và composer

Để tạo project laravel project cần có `composer` và `php`, chúng ta có thể cài đặt 2 thành phần này ở trên máy và sau đó chạy câu lệnh để tạo project, các hướng dẫn này có thể được tìm thấy trên mạng

Mình dùng 1 cách khác là sử dụng docker. Đầu tiên mình cần 1 docker image mà trong đó có cả 2 thành phần `php` và `composer`, sau đó mình dùng docker để build ra image như mong muốn

Dockerfile:

```Dockerfile
FROM composer:2.4 AS composer

FROM php:8.1-zts-alpine AS php
COPY --from=composer /usr/bin/composer /usr/bin/composer
```

Build docker image:

```bash
docker build -t phpwcomposer:v1 -f Dockerfile .
```

Có thể cần disable `DOCKER_BUILDKIT` để build được image

```bash
export DOCKER_BUILDKIT=0
```

### Chuẩn bị application docker volume

Cần có 1 volume chứa dữ liệu source code để để cho service  `nginx` và `phpfpm` có thể mount vào và sử dụng:

Mình tạo volume với command như sau:

```bash
docker volume create app-data
```

### Tạo project laravel

Sau khi tạo xong image ở trên có tên là `phpwcomposer:v1` (đã bao gồm php và composer như mong muốn) và đã có volume `app-data` để chứa source code

Mình thực hiện tạo 1 project laravel sample bằng command sau:

```bash
 docker run -ti -v app-data:/laravel-app phpwcomposer:v1 composer create-project laravel/laravel /laravel-app --prefer-dist
```

Sau khi tạo project thì dữ liệu của laravel project này nằm bên trong volume `app-data`

### Chuẩn bị docker volume khác

Nếu bạn cần thêm 1 volume để chứa logs thì có thể tạo thêm 1 volume khác và mount vào đường dẫn `<source_code>/storage/logs`

```bash
docker volume create app-logss
```

Thực tế cần có 1 volume sử dụng để lưu MySQL Server data nữa, nhưng trong ví dụ này mình không sử dụng

Nhớ phải khai báo volume external bên trong `docker-compose.yaml`

```yaml
volumes:
  app-data:
    external: true
  app-logs:
    external: true
```

## Chuẩn bị docker-compose file

Dockerfile:

```yaml
services:
  nginx:
    image: "nginx:$NGINX_VERSION"
    ports:
      - "8081:80"
    volumes:
      - app-data:/laravel-app
      - ./templates:/etc/nginx/templates
      - ./templates/nginx.conf:/etc/nginx/nginx.conf
      - ./templates/info.php:/laravel-app/public/info.php
    networks:
      - app-networks

  phpfpm:
    build: 
      context: ./phpfpm
      args:
        - PHP_FPM_VERSION=${PHP_FPM_VERSION}
    expose:
      - 9000
    environment:
      - DB_HOST=mysql
      - DB_DATABASE=${APP_DATABASE}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${MYSQL_ROOT_PASSWORD}
    volumes:
      - app-data:/laravel-app
      - ./templates/info.php:/laravel-app/public/info.php
      - app-logs:/laravel-app/storage/logs
    networks:
      - app-networks

  mysql:
    image: "mysql:$MYSQL_VERSION"
    expose:
      - 3306
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${APP_DATABASE}
    networks:
      - app-networks

networks:
  app-networks:
    driver: bridge
volumes:
  app-data:
    external: true
```

### Một số lưu ý

- Tất cả environment của `docker-compose.yaml` được khai báo bên trong file `.env`
- 3 container cần có networks chung với nhau
- Container `nginx` và `phpfpm` cần mount volume chứa source code laravel vào
-Khai báo environment để MySQL Server có thể start được
- Khai báo environment trong `phpfpm` service để laravel application có thể kết nối vào MySQL server

## Khởi động ứng dụng

Dùng command `docker compose up -d` để khởi động docker compose

```bash
❯ docker compose up -d
[+] Running 4/4
 ⠿ Network laravel-website_app-networks    Created  0.1s
 ⠿ Container laravel-website-mysql-1       Started  3.0s
 ⠿ Container laravel-website-phpfpm-1      Started  3.0s 
 ⠿ Container laravel-website-nginx-1       Started  2.8s 
```

Bây giờ bạn có thể truy cập vào `http://localhost:8081/` để vào website laravel

Mình expose port `8081` cho nginx được khai báo trong file docker-compose, có thể thay thế bằng bất kỳ port này bạn muốn

## Kiểm tra kết nối database từ application vào database server

Mình  sẽ đã khai báo các thông tin kết nối database trong container `phpfpm` trên `docker-compose.yml` để laravel có thể kết nối tới database

Mình dùng luôn user `root` của MySQL để kiểm tra cho nhanh, tất nhiên trong môi trường production không bao giờ khai báo user `root` trong ứng dụng của mình cả

```yaml
      - DB_HOST=mysql
      - DB_DATABASE=${APP_DATABASE}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${MYSQL_ROOT_PASSWORD}
```

`DB_HOST=mysql`  là giống với tên của service MySQL trong docker compose file

Sử dụng command sau để Laravel tự động tạo một số các tables mặc định

```bash
root@5230d54abe4e:/var/www/html# cd /laravel-app/
root@5230d54abe4e:/laravel-app# php artisan migrate
```

Kết qả:

```bash
   INFO  Preparing database.  

  Creating migration table ........................................... 32ms DONE

   INFO  Running migrations.  

  2014_10_12_000000_create_users_table ............................... 69ms DONE
  2014_10_12_100000_create_password_resets_table ..................... 44ms DONE
  2019_08_19_000000_create_failed_jobs_table ......................... 50ms DONE
  2019_12_14_000001_create_personal_access_tokens_table .............. 70ms DONE
```

Sử dụng tinker để access vào database

```bash
php artisan tinker
```

Show ra các tables có trong database

```bash
\DB::select('show tables');
```

Kết quả:

```bash
root@5230d54abe4e:/laravel-app# php artisan tinker
Psy Shell v0.11.9 (PHP 8.1.12 — cli) by Justin Hileman
> \DB::select('show tables');
= [
    {#3678
      +"Tables_in_appdb": "failed_jobs",
    },
    {#3680
      +"Tables_in_appdb": "migrations",
    },
    {#3681
      +"Tables_in_appdb": "password_resets",
    },
    {#3682
      +"Tables_in_appdb": "personal_access_tokens",
    },
    {#3683
      +"Tables_in_appdb": "users",
    },
  ]
> 
```
