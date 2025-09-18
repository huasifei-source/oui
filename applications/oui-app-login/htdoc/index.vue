<template>
  <div class="login-container">
    <!-- Brand Logo Section -->
    <div class="brand-logo">
      <!-- Logo placeholder - replace with actual logo -->
      <div class="logo-placeholder">
        <div class="logo-icon">LOGO</div>
        <div class="brand-name">Your Brand</div>
      </div>
    </div>
    
    <el-card class="login">
      <template #header>
        <div class="header">{{ $t('Login') }}</div>
      </template>
      <el-form ref="form" :model="formValue" :rules="rules" label-width="80px" label-suffix=":" size="large">
      <el-form-item v-if="showUserNameInput" :label="$t('Username')" prop="username">
        <el-input v-model="formValue.username" prefix-icon="user" :placeholder="$t('Please enter username')" @keyup.enter="login" autofocus/>
      </el-form-item>
      <el-form-item :label="$t('Password')" prop="password">
        <el-input type="password" v-model="formValue.password" prefix-icon="lock" :placeholder="$t('Please enter password')" @keyup.enter="login" show-password autofocus/>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" :loading="loading" @click="login" class="login-button">{{ $t('Login') }}</el-button>
      </el-form-item>
    </el-form>
    <el-divider/>
  </el-card>
  </div>
</template>

<script>
export default {
  data() {
    return {
      loading: false,
      showUserNameInput: false,
      formValue: {
        username: '',
        password: '123456'
      },
      rules: {
        username: {
          required: true,
          trigger: 'blur',
          message: () => this.$t('Please enter username')
        }
      }
    }
  },
  methods: {
    login() {
      this.$refs.form.validate(async valid => {
        if (!valid)
          return

        this.loading = true

        try {
          await this.$oui.login("admin", this.formValue.password)
          this.$router.push('/')
        } catch {
          this.$message.error(this.$t('wrong username or password'))
        }

        this.loading = false
      })
    }
  }
}
</script>

<style scoped>
/* Login container with blue gradient background */
.login-container {
  min-height: 100vh;
  background: linear-gradient(135deg, #e3f2fd 0%, #1e88e5 50%, #0d47a1 100%);
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 20px;
  position: relative;
}

/* Brand logo section */
.brand-logo {
  margin-bottom: 40px;
  text-align: center;
  animation: fadeInDown 1s ease-out;
}

.logo-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.logo-icon {
  width: 80px;
  height: 80px;
  background: linear-gradient(135deg, #64b5f6, #1976d2);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  font-weight: bold;
  color: white;
  box-shadow: 0 8px 32px rgba(25, 118, 210, 0.3);
  border: 3px solid rgba(255, 255, 255, 0.2);
}

.brand-name {
  font-size: 24px;
  font-weight: 600;
  color: #0d47a1;
  text-shadow: 0 2px 4px rgba(255, 255, 255, 0.5);
  letter-spacing: 1px;
}

/* Login card styles */
.login {
  width: 420px;
  max-width: 90vw;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  box-shadow: 0 16px 40px rgba(13, 71, 161, 0.2);
  border-radius: 16px;
  animation: fadeInUp 1s ease-out 0.3s both;
}

.header {
  text-align: center;
  font-size: 28px;
  font-weight: 600;
  color: #0d47a1;
  margin: 10px 0;
}

.login-button {
  width: 100%;
  background: linear-gradient(135deg, #42a5f5, #1976d2);
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 600;
  padding: 12px 0;
  transition: all 0.3s ease;
}

.login-button:hover {
  background: linear-gradient(135deg, #1976d2, #0d47a1);
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(25, 118, 210, 0.4);
}

.copyright {
  text-align: center;
  font-size: 12px;
  color: #1565c0;
  margin-top: 10px;
}

.copyright a {
  color: #1976d2;
  text-decoration: none;
  font-weight: 500;
}

.copyright a:hover {
  color: #0d47a1;
  text-decoration: underline;
}

/* Form customization */
:deep(.el-form-item__label) {
  color: #1565c0 !important;
  font-weight: 500;
}

:deep(.el-input__wrapper) {
  border-radius: 8px;
  border: 1px solid #bbdefb;
  transition: all 0.3s ease;
}

:deep(.el-input__wrapper:hover) {
  border-color: #64b5f6;
}

:deep(.el-input__wrapper.is-focus) {
  border-color: #1976d2;
  box-shadow: 0 0 0 2px rgba(25, 118, 210, 0.2);
}

:deep(.el-divider) {
  border-color: #e1f5fe;
}

/* Animations */
@keyframes fadeInDown {
  from {
    opacity: 0;
    transform: translateY(-30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Responsive design */
@media (max-width: 480px) {
  .login {
    width: 95vw;
    margin: 0 10px;
  }
  
  .brand-logo {
    margin-bottom: 30px;
  }
  
  .logo-icon {
    width: 60px;
    height: 60px;
    font-size: 14px;
  }
  
  .brand-name {
    font-size: 20px;
  }
  
  .header {
    font-size: 24px;
  }
}
</style>

<i18n src="./locale.json"/>
