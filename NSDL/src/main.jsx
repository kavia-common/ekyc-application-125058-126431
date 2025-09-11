import React from 'react'
import { createRoot } from 'react-dom/client'
function App(){return React.createElement('div',null,'NSDL Dev Environment')}
const root=document.createElement('div');root.id='root';document.body.appendChild(root);createRoot(root).render(React.createElement(App));
