import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET || JWT_SECRET.length < 32) {
  throw new Error('Defina JWT_SECRET (mínimo 32 caracteres) no arquivo backend/.env');
}

export function gerarToken(usuario) {
  return jwt.sign(
    { id: usuario.id, perfil: usuario.perfil, nome: usuario.nome },
    JWT_SECRET,
    { expiresIn: '30d' },
  );
}

export function exigirLogin(req, res, next) {
  const [tipo, token] = (req.headers.authorization || '').split(' ');
  if (tipo !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Faça login para continuar.' });
  }
  try {
    req.usuario = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Sessão expirada. Faça login novamente.' });
  }
}

export function exigirPerfil(perfil) {
  return (req, res, next) => {
    if (req.usuario?.perfil !== perfil) {
      return res.status(403).json({ error: 'Seu perfil não tem acesso a esta ação.' });
    }
    next();
  };
}
