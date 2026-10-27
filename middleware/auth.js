const jwt=require('jsonwebtoken');
function auth(req,res,next){try{const token=req.cookies.session;if(!token) return res.status(401).json({error:'Please sign in'});const user=jwt.verify(token,process.env.JWT_SECRET,{algorithms:['HS256']});req.user={id:user.id,role:user.role};next();}catch{return res.status(401).json({error:'Session expired. Sign in again'});}}
function admin(req,res,next){if(req.user.role!=='admin')return res.status(403).json({error:'Administrator only'});next();}
module.exports={auth,admin};
