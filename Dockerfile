FROM nginx:alpine
COPY playstore_assets/privacy_policy.html /usr/share/nginx/html/index.html
COPY playstore_assets/app_icon_512.png /usr/share/nginx/html/favicon.png
COPY playstore_assets/app_icon_512.png /usr/share/nginx/html/favicon.ico
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

