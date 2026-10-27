const router=require('express').Router();const db=require('../supabase');const {auth,admin}=require('../middleware/auth');router.use(auth,admin);
router.get('/overview',async(req,res,next)=>{try{const [u,i]=await Promise.all([db.from('users').select('id,name,email,role,created_at').order('created_at',{ascending:false}),db.from('invoices').select('total,status')]);if(u.error||i.error)throw u.error||i.error;res.json({users:u.data,invoice_count:i.data.length,paid_total:i.data.filter(x=>x.status==='paid').reduce((s,x)=>s+Number(x.total),0)});}catch(e){next(e)}});
module.exports=router;
