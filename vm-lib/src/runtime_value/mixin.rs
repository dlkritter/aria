// SPDX-License-Identifier: Apache-2.0
use std::{cell::RefCell, rc::Rc};

use rustc_data_structures::fx::FxHashSet;

use crate::{builtins::VmGlobals, runtime_value::object::ObjectBox, symbol::Symbol};

use super::RuntimeValue;

pub(super) struct MixinImpl {
    name: String,
    pub(super) entries: ObjectBox,
    mixins: RefCell<crate::mixin_includer::MixinIncluder>,
}

impl MixinImpl {
    fn new(name: &str) -> Self {
        Self {
            name: name.to_owned(),
            entries: ObjectBox::default(),
            mixins: RefCell::new(crate::mixin_includer::MixinIncluder::default()),
        }
    }

    fn load_named_value(&self, builtins: &VmGlobals, name: Symbol) -> Option<RuntimeValue> {
        if let Some(val) = self.entries.read(builtins, name) {
            Some(val.clone())
        } else {
            self.mixins.borrow().load_named_value(builtins, name)
        }
    }

    fn named_values(&self, builtins: &VmGlobals) -> Vec<Symbol> {
        self.entries.list_attributes(builtins).into_iter().collect()
    }

    fn include_mixin(&self, mixin: &Mixin) {
        self.mixins.borrow_mut().include(mixin.clone());
    }

    fn isa_mixin(&self, mixin: &Mixin) -> bool {
        self.mixins.borrow().contains(mixin)
    }

    fn list_attributes(&self, builtins: &VmGlobals) -> FxHashSet<Symbol> {
        let mut attrs = self.entries.list_attributes(builtins);
        attrs.extend(self.mixins.borrow().list_attributes(builtins));
        attrs
    }
}

#[derive(Clone)]
pub struct Mixin {
    pub(super) imp: Rc<MixinImpl>,
}

impl Mixin {
    pub fn new(name: &str) -> Self {
        Self {
            imp: Rc::new(MixinImpl::new(name)),
        }
    }

    pub fn name(&self) -> &str {
        &self.imp.name
    }

    pub fn load_named_value(&self, builtins: &VmGlobals, name: Symbol) -> Option<RuntimeValue> {
        self.imp.load_named_value(builtins, name)
    }

    pub fn named_values(&self, builtins: &VmGlobals) -> Vec<Symbol> {
        self.imp.named_values(builtins)
    }

    pub fn include_mixin(&self, mixin: &Mixin) {
        self.imp.include_mixin(mixin);
    }

    pub fn isa_mixin(&self, mixin: &Mixin) -> bool {
        self == mixin || self.imp.isa_mixin(mixin)
    }

    pub fn list_attributes(&self, builtins: &VmGlobals) -> FxHashSet<Symbol> {
        self.imp.list_attributes(builtins)
    }
}

impl PartialEq for Mixin {
    fn eq(&self, other: &Self) -> bool {
        Rc::ptr_eq(&self.imp, &other.imp)
    }
}
impl Eq for Mixin {}
