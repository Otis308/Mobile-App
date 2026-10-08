// Chạy: node scripts/smoke-test.mjs https://mobile-app-u103.onrender.com/api
// (không truyền địa chỉ thì mặc định http://localhost:3000/api). Cần Node 18+.
const API = (process.argv[2] ?? 'http://localhost:3000/api').replace(/\/$/, '');
const run = Date.now().toString().slice(-7);
const PASSWORD = 'Test@12345';
let failed = 0;

async function call(method, path, token, body) {
  const res = await fetch(API + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let data = null;
  try { data = await res.json(); } catch { /* không có body */ }
  return { status: res.status, data };
}

const brief = (r) => `HTTP ${r.status} ${JSON.stringify(r.data)?.slice(0, 180)}`;

function check(name, ok, r) {
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${ok ? '' : `\n        -> ${r ? brief(r) : ''}`}`);
}

function register(tag) {
  return call('POST', '/auth/register', null, {
    email: `smoke_${tag}_${run}@example.com`,
    username: `smoke${tag}${run}`,
    fullName: `Smoke ${tag.toUpperCase()}`,
    password: PASSWORD,
    phone: '0900000000',
    dob: '2000-01-01',
    gender: 'Nam',
  });
}

console.log(`API: ${API}\n(Lần gọi đầu tới Render có thể mất ~1 phút nếu server đang ngủ)\n`);

// 1. Tài khoản
const a = await register('a');
check('Đăng ký tài khoản A', a.status === 201 && !!a.data?.accessToken, a);
const b = await register('b');
check('Đăng ký tài khoản B', b.status === 201 && !!b.data?.accessToken, b);
if (!a.data?.accessToken || !b.data?.accessToken) {
  console.log('\nDừng: không đăng ký được tài khoản thử nghiệm.');
  process.exit(1);
}
const tokA = a.data.accessToken;
const tokB = b.data.accessToken;
const idB = b.data.user._id;
const usernameB = b.data.user.username;

let r = await call('POST', '/auth/login', null, { login: `smokea${run}`, password: PASSWORD });
check('Đăng nhập bằng username', r.status === 201 && !!r.data?.accessToken, r);

r = await call('GET', '/users/me', tokA);
check('GET /users/me (lỗi cũ: 401)', r.status === 200 && !!r.data?._id, r);

// 2. Dự án
r = await call('POST', '/projects', tokA, { name: `Smoke Project ${run}`, description: 'Kiểm thử tự động', color: '3E6FF2' });
check('Tạo dự án', r.status === 201 && !!r.data?._id, r);
const pid = r.data?._id;
if (!pid) process.exit(1);

r = await call('GET', `/projects/${pid}`, tokA);
check('Chủ dự án xem được dự án của mình (lỗi cũ: 403)', r.status === 200, r);

r = await call('GET', `/projects/${pid}/members`, tokA);
check('Chủ dự án xem được danh sách thành viên (lỗi cũ: 403)', r.status === 200 && r.data?.length === 1, r);

r = await call('GET', `/projects/${pid}/tasks`, tokB);
check('Người ngoài dự án bị chặn (403)', r.status === 403, r);

// 3. Mời thành viên
r = await call('GET', `/users/search?q=${encodeURIComponent(usernameB)}`, tokA);
check('Tìm người dùng để mời (lỗi cũ: 401)', r.status === 200 && r.data?.some((u) => u._id === idB), r);

r = await call('POST', `/projects/${pid}/members`, tokA, { userId: idB, role: 'member' });
check('Mời B vào dự án', r.status === 201, r);

r = await call('GET', `/projects/${pid}/members`, tokA);
check('Dự án có 2 thành viên', r.status === 200 && r.data?.length === 2, r);

r = await call('GET', `/projects/${pid}/tasks`, tokB);
check('B (đã được mời) xem được task', r.status === 200 && Array.isArray(r.data), r);

// 4. Task
const due = new Date(Date.now() + 36 * 3600 * 1000).toISOString();
r = await call('POST', `/projects/${pid}/tasks`, tokA, {
  title: 'Task thử nghiệm', description: 'mô tả', priority: 'high',
  assigneeId: idB, dueDate: due, labels: ['smoke', 'api'],
});
check('Tạo task giao cho B', r.status === 201 && !!r.data?._id, r);
const tid = r.data?._id;
if (!tid) process.exit(1);

r = await call('GET', `/projects/${pid}/tasks`, tokA);
check('Danh sách task có 1 task', r.status === 200 && r.data?.length === 1, r);

r = await call('PATCH', `/tasks/${tid}`, tokB, { title: 'Task đã đổi tên' });
check('Sửa tiêu đề task', r.status === 200 && r.data?.title === 'Task đã đổi tên', r);
check('Sửa tiêu đề KHÔNG làm mất hạn chót và người thực hiện', !!r.data?.dueDate && r.data?.assigneeId === idB, r);

r = await call('PATCH', `/tasks/${tid}/move`, tokB, { status: 'doing', order: 0 });
check('Kéo task sang "Đang làm"', r.status === 200 && r.data?.status === 'doing', r);

r = await call('PATCH', `/tasks/${tid}`, tokA, { assigneeId: null, dueDate: null });
check('Bỏ giao việc và xóa hạn', r.status === 200 && !r.data?.assigneeId && !r.data?.dueDate, r);

// 5. Bình luận, thông báo, tổng quan
r = await call('POST', `/tasks/${tid}/comments`, tokB, { content: 'Bình luận thử nghiệm' });
check('B bình luận', r.status === 201, r);
r = await call('GET', `/tasks/${tid}/comments`, tokA);
check('A đọc được bình luận', r.status === 200 && r.data?.length === 1, r);

r = await call('GET', '/dashboard', tokA);
check('Tổng quan của A', r.status === 200 && r.data?.totalProjects >= 1, r);

r = await call('GET', '/notifications', tokB);
check('B nhận được thông báo (được mời / được giao)', r.status === 200 && r.data?.length >= 1, r);

// 6. Quản lý nhóm (tính năng 4)
r = await call('PATCH', `/projects/${pid}/members/${idB}`, tokA, { role: 'manager' });
check('[TN4] Nâng B lên Quản lý', r.status === 200, r);

r = await call('DELETE', `/projects/${pid}`, tokB);
check('[TN4] Quản lý KHÔNG được xóa dự án (chỉ chủ dự án)', r.status === 403, r);

r = await call('DELETE', `/tasks/${tid}`, tokA);
check('Xóa task', r.status === 200, r);

r = await call('DELETE', `/projects/${pid}/members/${idB}`, tokA);
check('[TN4] Xóa B khỏi nhóm', r.status === 200, r);

r = await call('GET', `/projects/${pid}/tasks`, tokB);
check('[TN4] B mất quyền truy cập sau khi bị xóa', r.status === 403, r);

r = await call('DELETE', `/projects/${pid}`, tokA);
check('Chủ dự án xóa dự án', r.status === 200, r);

console.log(`\n${failed === 0 ? 'TẤT CẢ ĐỀU PASS' : `CÓ ${failed} BƯỚC FAIL`}`);
console.log('Ghi chú: hai tài khoản smoke_* vẫn nằm trong DB, bạn có thể bỏ qua hoặc xóa thủ công.');
process.exit(failed === 0 ? 0 : 1);