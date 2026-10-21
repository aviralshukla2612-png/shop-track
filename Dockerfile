FROM nginx:alpine
COPY playstore_assets/privacy_policy.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
