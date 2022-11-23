FROM composer:2.4 AS composer

FROM php:8.1-zts-alpine AS php
COPY --from=composer /usr/bin/composer /usr/bin/composer